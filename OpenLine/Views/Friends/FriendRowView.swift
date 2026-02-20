//
//  FriendRowView.swift
//  OpenLine
//
//  Created by Andrew Shea on 8/8/25.
//
import SwiftUI

struct FriendRowView: View {
    let friend: Friend
    let canCall: Bool
    let category: String
    @StateObject private var contactVerifier = ContactVerificationManager.shared

    var body: some View {
        HStack(spacing: 14) {
            // LED Status Indicator - the trading floor signature
            ledIndicator

            // Contact info
            VStack(alignment: .leading, spacing: 3) {
                Text(friend.name)
                    .font(TurretTheme.statusFont(size: 17))
                    .foregroundColor(.primary)

                // Show status text
                Text(friend.displayStatus)
                    .font(TurretTheme.bodyFont(size: 13))
                    .foregroundColor(.secondary)

                if let message = availabilityMessage {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text(message)
                            .font(TurretTheme.captionFont(size: 12))
                    }
                    .foregroundColor(Color(UIColor.tertiaryLabel))
                }
            }

            Spacer()

            // Call button
            if canCall {
                Button(action: callFriend) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(TurretTheme.ledGreen.opacity(0.12))
                            .frame(width: 40, height: 40)

                        Image(systemName: "phone.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(TurretTheme.ledGreen)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - LED Indicator
    private var ledIndicator: some View {
        Circle()
            .fill(ledColor)
            .frame(width: 12, height: 12)
            .shadow(color: ledColor.opacity(0.3), radius: 2)
    }

    // MARK: - LED Color
    private var ledColor: Color {
        // Use actual status to determine color, not just category
        switch friend.displayStatus {
        case "Available":
            return TurretTheme.ledGreen
        case "Unavailable":
            return TurretTheme.ledRed
        case "No Status":
            return TurretTheme.ledAmber
        default:
            return TurretTheme.ledAmber
        }
    }

    // MARK: - Availability Message
    private var availabilityMessage: String? {
        let now = Date()

        if let until = friend.availableUntil, until > now && friend.displayStatus == "Available" {
            return formatAvailableFor(until: until)
        } else if let until = friend.availableUntil, until > now && friend.displayStatus != "Available" {
            return formatAvailableIn(until: until)
        } else {
            return nil
        }
    }

    private func formatAvailableFor(until: Date) -> String {
        let timeInterval = until.timeIntervalSince(Date())
        let hours = Int(timeInterval) / 3600
        let minutes = (Int(timeInterval) % 3600) / 60

        if hours > 0 {
            return "Available for \(hours)hr \(minutes)m"
        } else {
            return "Available for \(minutes)m"
        }
    }

    private func formatAvailableIn(until: Date) -> String {
        let timeInterval = until.timeIntervalSince(Date())
        let hours = Int(timeInterval) / 3600
        let minutes = (Int(timeInterval) % 3600) / 60

        if hours > 0 {
            return "Free in \(hours)hr \(minutes)m"
        } else {
            return "Free in \(minutes)m"
        }
    }

    private func callFriend() {
        let cleanedNumber = friend.phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        guard !cleanedNumber.isEmpty else { return }
        if let url = URL(string: "tel://\(cleanedNumber)") {
            UIApplication.shared.open(url)
        }
    }
}
