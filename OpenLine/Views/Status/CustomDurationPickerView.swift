//
//  CustomDurationPickerView.swift
//  OpenLine
//
//  Created by Andrew Shea on 8/8/25.
//
import SwiftUI

struct CustomDurationPickerView: View {
    @Binding var hours: Int
    @Binding var minutes: Int
    @Binding var isPresented: Bool
    let onSave: (Int, Int) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    Picker("Hours", selection: $hours) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text("\(hour) hr").tag(hour)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    
                    Picker("Minutes", selection: $minutes) {
                        ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) { minute in
                            Text("\(minute) min").tag(minute)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("Custom Duration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(hours, minutes)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
