//
//  AppError.swift
//  OpenLine
//
//  Created by Andrew Shea on 8/8/25.
//
import Foundation

enum AppError: LocalizedError {
    case networkError(String)
    case syncError(String)
    case authenticationError(String)
    case dataError(String)
    case cloudKitError(String)
    case notificationError(String)
    case subscriptionError(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Network Error: \(message)"
        case .syncError(let message):
            return "Sync Error: \(message)"
        case .authenticationError(let message):
            return "Authentication Error: \(message)"
        case .dataError(let message):
            return "Data Error: \(message)"
        case .cloudKitError(let message):
            return "CloudKit Error: \(message)"
        case .notificationError(let message):
            return "Notification Error: \(message)"
        case .subscriptionError(let message):
            return "Subscription Error: \(message)"
        case .unknown(let message):
            return "Error: \(message)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .networkError:
            return "Please check your internet connection and try again."
        case .syncError:
            return "Your data may not be up to date. Pull to refresh."
        case .authenticationError:
            return "Please sign in to iCloud in Settings."
        case .dataError:
            return "There was a problem with your data. Please try again."
        case .cloudKitError:
            return "There was a problem with iCloud. Please try again later."
        case .notificationError:
            return "Please enable notifications in Settings to receive friend request alerts."
        case .subscriptionError:
            return "There was a problem setting up real-time updates. Pull to refresh manually."
        case .unknown:
            return "Please try again. If the problem persists, restart the app."
        }
    }
}
