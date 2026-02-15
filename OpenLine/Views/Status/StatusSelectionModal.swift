//
//  StatusSelectionModal.swift
//  OpenLine
//
//  Created by Andrew Shea on 8/8/25.
//
import SwiftUI

struct StatusSelectionModal: View {
    @ObservedObject var viewModel: OpenLineViewModel
    @Binding var isPresented: Bool
    @State private var selectedStatus: StatusType = .available
    @State private var selectedDuration = 120
    @State private var showingCustomPicker = false
    @State private var customHours = 0
    @State private var customMinutes = 30
    @Environment(\.dismiss) private var dismiss
    
    private let durationOptions = [
        (30, "30 min"),
        (60, "1 hour"),
        (120, "2 hours"),
        (240, "4 hours"),
        (480, "8 hours"),
        (1440, "All day")
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                statusSelectionSection
                
                if selectedStatus != .noStatus {
                    durationSelectionSection
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Update Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Update") {
                        updateStatus()
                        dismiss()
                    }
                    .fontWeight(.semibold)
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
        }
        .onChange(of: selectedStatus) { _ in
            // Always use app Default Status Duration regardless of status
            selectedDuration = viewModel.defaultStatusDuration
        }
    }
    
    private var statusSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select Status")
                .font(.headline)
            
            ForEach(StatusType.allCases, id: \.self) { status in
                Button(action: { selectedStatus = status }) {
                    HStack {
                        Circle()
                            .fill(statusDisplayColor(for: status))
                            .frame(width: 12, height: 12)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(status.rawValue)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text(status.defaultMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if selectedStatus == status {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(12)
                    .background(selectedStatus == status ? Color.blue.opacity(0.1) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private var durationSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(durationLabel)
                .font(.headline)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(durationOptions, id: \.0) { duration, label in
                    Button(action: { selectedDuration = duration }) {
                        Text(label)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(selectedDuration == duration ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(selectedDuration == duration ? Color.blue : Color.gray.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            Button("Custom") {
                showingCustomPicker = true
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    private var durationLabel: String { "Status Duration" }
    
    private func updateStatus() {
        let until = selectedStatus == .noStatus ? nil : Calendar.current.date(byAdding: .minute, value: selectedDuration, to: Date())
        
        viewModel.updateCurrentStatus(
            status: selectedStatus.rawValue,
            message: selectedStatus.defaultMessage,
            until: until
        )
        
        viewModel.setLastUsedDuration(selectedDuration, for: selectedStatus)
    }
    
    private func statusDisplayColor(for status: StatusType) -> Color {
        switch status {
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
}
