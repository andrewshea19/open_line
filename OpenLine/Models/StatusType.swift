//
//  StatusType.swift
//  OpenLine
//
//  Created by Andrew Shea on 8/8/25.
//
import Foundation
import SwiftUI

enum StatusType: String, CaseIterable {
    case available = "Available"
    case unavailable = "Unavailable"
    case noStatus = "No Status"
}

extension StatusType {
    var defaultMessage: String {
        switch self {
        case .available:
            return "Free for calls!"
        case .unavailable:
            return "Can't talk right now"
        case .noStatus:
            return ""
        }
    }

    var color: Color {
        switch self {
        case .available:
            return .green
        case .noStatus:
            return .orange
        case .unavailable:
            return .red
        }
    }
}
