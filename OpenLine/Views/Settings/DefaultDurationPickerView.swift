//
//  DefaultDurationPickerView.swift
//  OpenLine
//
//  Created by Andrew Shea on 8/8/25.
//
import SwiftUI

struct DefaultDurationPickerView: View {
    @Binding var selectedDuration: Int
    @Binding var isPresented: Bool
    @Environment(\.dismiss) private var dismiss

    private let durationOptions = [
        (30, "30 minutes"),
        (60, "1 hour"),
        (120, "2 hours"),
        (240, "4 hours"),
        (480, "8 hours"),
        (1440, "All day")
    ]

    var body: some View {
        NavigationView {
            List {
                ForEach(durationOptions, id: \.0) { duration, label in
                    Button(action: {
                        selectedDuration = duration
                        dismiss()
                    }) {
                        HStack {
                            Text(label)
                                .font(TurretTheme.statusFont(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedDuration == duration {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Default Duration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(TurretTheme.statusFont(size: 17))
                }
            }
        }
    }
}
