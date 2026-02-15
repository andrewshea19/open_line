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
        HStack(spacing: 12) {
            // Status indicator with modern style
            ZStack {
                Circle()
                    .fill(categoryColor)
                    .frame(width: 14, height: 14)
                    .shadow(color: categoryColor.opacity(0.4), radius: 3, x: 0, y: 1)
                
                Circle()
                    .strokeBorder(.white.opacity(0.3), lineWidth: 2)
                    .frame(width: 14, height: 14)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(friend.name)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                    
                    if contactVerifier.isPhoneNumberInContacts(friend.phoneNumber) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                }
                
                if let message = friend.statusMessage, !message.isEmpty {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // Category-based availability message
                if let message = availabilityMessage {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.caption2)
                        Text(message)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if canCall {
                Button {
                    callFriend()
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.green, .green.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .green.opacity(0.3), radius: 4, x: 0, y: 2)

                        Image(systemName: "phone.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 40, height: 40)
                    .contentShape(Circle())
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
    
    // Category-based dot color
    private var categoryColor: Color {
        switch category {
        case AppConstants.Category.availableNow:
            return .green
        case AppConstants.Category.availableSoon:
            return .yellow
        case AppConstants.Category.notAvailable:
            return .red
        default:
            return .orange // For "No Status" or other cases
        }
    }
    
    // Category-based availability message
    private var availabilityMessage: String? {
        let now = Date()
        
        if let until = friend.availableUntil, until > now && friend.displayStatus == "Available" {
            // Available Now - "Available for..."
            return formatAvailableFor(until: until)
        } else if let until = friend.availableUntil, until > now && friend.displayStatus != "Available" {
            // Available Soon - "Available in..."
            return formatAvailableIn(until: until)
        } else {
            // Not Available - no message
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
            return "Available in \(hours)hr \(minutes)m"
        } else {
            return "Available in \(minutes)m"
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

