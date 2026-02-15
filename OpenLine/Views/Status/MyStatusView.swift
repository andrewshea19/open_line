//
//  MyStatusView.swift
//  OpenLine
//
//  Created by Andrew Shea on 8/8/25.
//
import SwiftUI

struct MyStatusView: View {
    @ObservedObject var viewModel: OpenLineViewModel
    @State private var showingStatusModal = false
    @State private var showingAddRecurring = false
    @State private var showingAddOneTime = false
    @State private var showingAddCommute = false
    @State private var showingCustomQuickDuration = false
    @State private var customQuickHours = 0
    @State private var customQuickMinutes = 30
    @GestureState private var dragOffset: CGFloat = 0
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    statusCardWithGestures
                    scheduleSection
                }
                .padding()
            }
            .navigationTitle("My Status")
        }
        .sheet(isPresented: $showingStatusModal) {
            StatusSelectionModal(viewModel: viewModel, isPresented: $showingStatusModal)
        }
        .sheet(isPresented: $showingAddRecurring) {
            AddScheduleView(viewModel: viewModel, isPresented: $showingAddRecurring, scheduleType: .recurring)
        }
        .sheet(isPresented: $showingAddOneTime) {
            AddScheduleView(viewModel: viewModel, isPresented: $showingAddOneTime, scheduleType: .oneTime)
        }
        .sheet(isPresented: $showingAddCommute) {
            AddScheduleView(viewModel: viewModel, isPresented: $showingAddCommute, scheduleType: .commute)
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
    
    private var statusCardWithGestures: some View {
        Button(action: { showingStatusModal = true }) {
            GlassStatusCard(
                gradient: LinearGradient(
                    colors: [
                        currentStatusType.color.opacity(0.28),
                        currentStatusType.color.opacity(0.14)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            ) {
                VStack(spacing: 12) {
                    HStack {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(currentStatusType.color)
                                    .frame(width: 16, height: 16)
                                    .shadow(color: currentStatusType.color.opacity(0.6), radius: 4, x: 0, y: 2)
                                
                                Circle()
                                    .strokeBorder(.white.opacity(0.3), lineWidth: 2)
                                    .frame(width: 16, height: 16)
                            }
                            
                            Text(viewModel.currentStatus)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.primary.opacity(0.5))
                    }
                    
                    VStack(spacing: 8) {
                        if !viewModel.statusMessage.isEmpty {
                            Text(viewModel.statusMessage)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                        }
                        
                        if let until = viewModel.statusUntil {
                            HStack {
                                Image(systemName: "clock.fill")
                                    .font(.caption)
                                Text("Until \(until, formatter: timeFormatter)")
                                    .font(.subheadline)
                            }
                            .foregroundStyle(.secondary)
                        }
                        
                        if viewModel.currentStatus != "No Status" {
                            HStack(spacing: 6) {
                                ForEach(AppConstants.quickExtendMinutes, id: \.self) { minutes in
                                    Button(formatQuickDuration(minutes)) {
                                        viewModel.extendCurrentStatus(by: minutes)
                                    }
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .frame(maxWidth: .infinity)
                                    .background {
                                        Capsule()
                                            .fill(.white.opacity(0.15))
                                            .overlay {
                                                Capsule()
                                                    .strokeBorder(.black.opacity(0.1), lineWidth: 1)
                                            }
                                    }
                                }
                                Button("Custom") {
                                    showingCustomQuickDuration = true
                                }
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity)
                                .background {
                                    Capsule()
                                        .fill(.white.opacity(0.15))
                                        .overlay {
                                            Capsule()
                                                .strokeBorder(.black.opacity(0.1), lineWidth: 1)
                                        }
                                }
                            }
                        }
                    }
                }
                .padding(14)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .offset(x: dragOffset)
        .gesture(
            DragGesture()
                .updating($dragOffset) { value, state, _ in
                    state = value.translation.width
                }
                .onEnded { value in
                    let threshold: CGFloat = 50
                    if value.translation.width > threshold {
                        viewModel.cycleToPreviousStatus()
                    } else if value.translation.width < -threshold {
                        viewModel.cycleToNextStatus()
                    }
                }
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dragOffset)
    }
    
    private var currentStatusType: StatusType {
        StatusType(rawValue: viewModel.currentStatus) ?? .noStatus
    }
    
    private var currentStatusDisplayColor: Color {
        switch currentStatusType {
        case .available:
            return .green
        case .commuting:
            return .green  // Same green as Available
        case .noStatus:
            return .orange
        case .unavailable:
            return .red
        @unknown default:
            return .gray
        }
    }
    
    private func formatQuickDuration(_ minutes: Int) -> String {
        if minutes < 60 {
            return "+\(minutes)m"
        } else {
            return "+\(minutes/60)hr"
        }
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
    
    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Your Schedule")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                
                Spacer()
                
                Menu {
                    Button("Recurring Schedule") {
                        showingAddRecurring = true
                    }
                    
                    Button("One-time Event") {
                        showingAddOneTime = true
                    }
                    
                    Button("Add Commute Schedule") {
                        showingAddCommute = true
                    }
                } label: {
                    ModernIconBadge(
                        icon: "plus",
                        color: .blue,
                        size: 36,
                        useNeutralStyle: true
                    )
                }
            }
            
            if viewModel.schedules.isEmpty {
                VStack(spacing: 16) {
                    ModernIconBadge(
                        icon: "calendar",
                        color: .secondary,
                        size: 60
                    )
                    
                    VStack(spacing: 6) {
                        Text("No schedules yet")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text("Add your first schedule to automatically manage your status")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ForEach(viewModel.sortedSchedules()) { schedule in
                    ScheduleRowView(schedule: schedule, viewModel: viewModel)
                }
            }
        }
        .glassCard()
    }
}

