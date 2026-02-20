//
//  OpenLineWidgetControl.swift
//  OpenLineWidget
//
//  Created by Andrew Shea on 2/17/26.
//

import AppIntents
import SwiftUI
import WidgetKit

struct OpenLineWidgetControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "com.shea.OpenLine.OpenLineWidgetControl",
            provider: AvailabilityControlProvider()
        ) { isAvailable in
            ControlWidgetToggle(
                "Availability",
                isOn: isAvailable,
                action: ToggleAvailabilityControlIntent()
            ) { isOn in
                Label(isOn ? "Available" : "Unavailable", systemImage: isOn ? "phone.circle.fill" : "phone.down.circle.fill")
            }
        }
        .displayName("Availability")
        .description("Toggle your availability status")
    }
}

struct AvailabilityControlProvider: ControlValueProvider {
    var previewValue: Bool {
        true
    }

    func currentValue() async throws -> Bool {
        return SharedDefaults.shared.isAvailable
    }
}

struct ToggleAvailabilityControlIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Toggle Availability"

    @Parameter(title: "Available")
    var value: Bool

    func perform() async throws -> some IntentResult {
        let shared = SharedDefaults.shared

        if value {
            shared.currentStatus = "Available"
            shared.statusMessage = "Free for calls!"
        } else {
            shared.currentStatus = "Unavailable"
            shared.statusMessage = "Can't talk right now"
        }

        let duration = shared.defaultDuration > 0 ? shared.defaultDuration : 120
        shared.statusUntil = Calendar.current.date(byAdding: .minute, value: duration, to: Date())

        WidgetCenter.shared.reloadAllTimelines()

        return .result()
    }
}
