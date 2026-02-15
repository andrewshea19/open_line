//
//  FriendRequestsView.swift
//  OpenLine
//
//  Created by Andrew Shea on 8/8/25.
//
import SwiftUI

struct FriendRequestsView: View {
    @ObservedObject var viewModel: OpenLineViewModel
    @State private var selectedTab: RequestTab = .incoming
    @Environment(\.dismiss) private var dismiss
    
    enum RequestTab: String, CaseIterable {
        case incoming = "Received"
        case sent = "Sent"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Picker
                Picker("Request Type", selection: $selectedTab) {
                    ForEach(RequestTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Content
                List {
                    Group {
                        switch selectedTab {
                        case .incoming:
                            receivedRequestsSection
                        case .sent:
                            sentRequestsSection
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
                .refreshable {
                    viewModel.fetchFriendRequests()
                }
            }
            .navigationTitle("Friend Requests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                viewModel.fetchFriendRequests()
            }
            .onReceive(Timer.publish(every: 30.0, on: .main, in: .common).autoconnect()) { _ in
                // Auto-refresh every 30 seconds while view is visible
                viewModel.fetchFriendRequests()
            }
        }
    }
    
    @ViewBuilder
    private var receivedRequestsSection: some View {
        if viewModel.pendingFriendRequests.isEmpty {
            Text("No received friend requests")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowBackground(Color.clear)
        } else {
            ForEach(viewModel.pendingFriendRequests) { request in
                IncomingFriendRequestRowView(request: request, viewModel: viewModel)
            }
        }
    }
    
    @ViewBuilder
    private var sentRequestsSection: some View {
        if viewModel.sentFriendRequests.isEmpty {
            VStack(spacing: 12) {
                Text("No sent friend requests")
                    .foregroundColor(.secondary)
                Text("Friend requests you send will appear here")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .listRowBackground(Color.clear)
        } else {
            ForEach(viewModel.sentFriendRequests) { request in
                SentFriendRequestRowView(request: request, viewModel: viewModel)
            }
        }
    }
}

struct IncomingFriendRequestRowView: View {
    let request: FriendRequest
    @ObservedObject var viewModel: OpenLineViewModel
    @State private var isResponding = false
    @StateObject private var contactVerifier = ContactVerificationManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main content row
            HStack(alignment: .center, spacing: 0) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(avatarGradient)
                        .frame(width: 42, height: 42)
                    
                    Text(avatarInitials)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.trailing, 12)
                
                // Info section
                VStack(alignment: .leading, spacing: 3) {
                    Text(request.fromUserName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        // Contact status badge
                        Text(isInContacts ? "Known" : "Unknown")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(isInContacts ? Color(red: 0.084, green: 0.341, blue: 0.145) : Color(red: 0.522, green: 0.392, blue: 0.024))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(isInContacts ? Color(red: 0.831, green: 0.925, blue: 0.855) : Color(red: 1.0, green: 0.949, blue: 0.804))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .fixedSize()
                        
                        // Time badge
                Text(timeAgo(from: request.createdAt))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.4))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(red: 0.941, green: 0.941, blue: 0.941))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .fixedSize()
                    }
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 8) {
                    Button {
                        respondToRequest(accept: true)
                    } label: {
                        Text("Accept")
                            .frame(width: 75, height: 42)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .disabled(isResponding)

                    Button {
                        respondToRequest(accept: false)
                    } label: {
                        Text("Decline")
                            .frame(width: 75, height: 42)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.red)
                            .background(Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.red, lineWidth: 2)
                            )
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .disabled(isResponding)
                }
            }
            .padding(.vertical, 8)
            
            // Message if present
            if let message = request.message, !message.isEmpty {
                HStack(alignment: .top, spacing: 0) {
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: 3)
                    
                    Text("\"\(message)\"")
                        .font(.system(size: 14))
                        .foregroundColor(Color(red: 0.084, green: 0.396, blue: 0.753))
                        .italic()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(red: 0.89, green: 0.949, blue: 0.992))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(.top, 10)
                .padding(.leading, 54) // Align with text content
            }
        }
        .padding(.vertical, 4)
    }
    
    private var avatarInitials: String {
        let components = request.fromUserName.components(separatedBy: " ")
        let initials = components.compactMap { $0.first }.map { String($0) }
        return initials.prefix(2).joined().uppercased()
    }
    
    private var avatarGradient: LinearGradient {
        let gradients = [
            LinearGradient(colors: [Color(red: 0.4, green: 0.675, blue: 0.918), Color(red: 0.463, green: 0.294, blue: 0.635)], startPoint: .topLeading, endPoint: .bottomTrailing),
            LinearGradient(colors: [Color(red: 0.941, green: 0.576, blue: 0.984), Color(red: 0.961, green: 0.341, blue: 0.424)], startPoint: .topLeading, endPoint: .bottomTrailing),
            LinearGradient(colors: [Color(red: 0.294, green: 0.675, blue: 0.992), Color(red: 0.0, green: 0.949, blue: 0.992)], startPoint: .topLeading, endPoint: .bottomTrailing),
            LinearGradient(colors: [Color(red: 0.263, green: 0.914, blue: 0.482), Color(red: 0.220, green: 0.976, blue: 0.843)], startPoint: .topLeading, endPoint: .bottomTrailing)
        ]
        
        let index = abs(request.fromUserName.hashValue) % gradients.count
        return gradients[index]
    }
    
    private var isInContacts: Bool {
        if contactVerifier.isPhoneNumberInContacts(request.fromUserPhone) {
            return true
        }
        
        if let email = request.fromUserEmail, contactVerifier.isEmailInContacts(email) {
            return true
        }
        
        return false
    }
    
    private func respondToRequest(accept: Bool) {
        isResponding = true
        viewModel.respondToFriendRequest(request, accept: accept) {
            isResponding = false
        }
    }
    
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct SentFriendRequestRowView: View {
    let request: FriendRequest
    @ObservedObject var viewModel: OpenLineViewModel
    @State private var showingCancelAlert = false
    @StateObject private var contactVerifier = ContactVerificationManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main content row
            HStack(alignment: .center, spacing: 0) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(avatarGradient)
                        .frame(width: 42, height: 42)
                    
                    Text(avatarInitials)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.trailing, 12)
                
                // Info section
                VStack(alignment: .leading, spacing: 3) {
                    Text(request.toUserName ?? "Unknown User")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        // Contact status badge
                        Text(isInContacts ? "In Contacts" : "Unknown")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(isInContacts ? Color(red: 0.084, green: 0.341, blue: 0.145) : Color(red: 0.522, green: 0.392, blue: 0.024))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(isInContacts ? Color(red: 0.831, green: 0.925, blue: 0.855) : Color(red: 1.0, green: 0.949, blue: 0.804))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                            .fixedSize()
                        
                        // Request status badge
                        Text(statusText)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(statusColor)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                            .fixedSize()
                        
                        // Time badge
                        Text(timeAgo(from: request.createdAt))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.4))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color(red: 0.941, green: 0.941, blue: 0.941))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .fixedSize()
                    }
                }
                
                Spacer()
                
                // Action button (only for pending requests)
                if request.status == .pending {
                    Button {
                        showingCancelAlert = true
                    } label: {
                        Text("Cancel")
                            .frame(width: 75, height: 42)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.red)
                            .background(Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.red, lineWidth: 2)
                            )
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
            .padding(.vertical, 8)
            
            // Message if present
            if let message = request.message, !message.isEmpty {
                HStack(alignment: .top, spacing: 0) {
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: 3)
                    
                    Text("\"\(message)\"")
                        .font(.system(size: 14))
                        .foregroundColor(Color(red: 0.084, green: 0.396, blue: 0.753))
                        .italic()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(red: 0.89, green: 0.949, blue: 0.992))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(.top, 10)
                .padding(.leading, 54) // Align with text content
            }
        }
        .padding(.vertical, 4)
        .alert("Cancel Friend Request", isPresented: $showingCancelAlert) {
            Button("Cancel Request", role: .destructive) {
                viewModel.cancelSentFriendRequest(request)
            }
            Button("Keep Request", role: .cancel) { }
        } message: {
            Text("Are you sure you want to cancel your friend request to \(request.toUserName ?? "this person")?")
        }
    }
    
    private var avatarInitials: String {
        let name = request.toUserName ?? "Unknown User"
        let components = name.components(separatedBy: " ")
        let initials = components.compactMap { $0.first }.map { String($0) }
        return initials.prefix(2).joined().uppercased()
    }
    
    private var avatarGradient: LinearGradient {
        let gradients = [
            LinearGradient(colors: [Color(red: 0.4, green: 0.675, blue: 0.918), Color(red: 0.463, green: 0.294, blue: 0.635)], startPoint: .topLeading, endPoint: .bottomTrailing),
            LinearGradient(colors: [Color(red: 0.941, green: 0.576, blue: 0.984), Color(red: 0.961, green: 0.341, blue: 0.424)], startPoint: .topLeading, endPoint: .bottomTrailing),
            LinearGradient(colors: [Color(red: 0.294, green: 0.675, blue: 0.992), Color(red: 0.0, green: 0.949, blue: 0.992)], startPoint: .topLeading, endPoint: .bottomTrailing),
            LinearGradient(colors: [Color(red: 0.263, green: 0.914, blue: 0.482), Color(red: 0.220, green: 0.976, blue: 0.843)], startPoint: .topLeading, endPoint: .bottomTrailing)
        ]
        
        let name = request.toUserName ?? "Unknown User"
        let index = abs(name.hashValue) % gradients.count
        return gradients[index]
    }
    
    private var statusText: String {
        switch request.status {
        case .pending: return "PENDING"
        case .accepted: return "ACCEPTED"
        case .declined: return "DECLINED"
        case .expired: return "EXPIRED"
        @unknown default: return "UNKNOWN"
        }
    }
    
    private var statusColor: Color {
        switch request.status {
        case .pending: return Color.orange
        case .accepted: return Color.green
        case .declined: return Color.red
        case .expired: return Color.gray
        @unknown default: return Color.gray
        }
    }
    
    private var isInContacts: Bool {
        guard let phone = request.toUserPhone else { return false }
        
        if contactVerifier.isPhoneNumberInContacts(phone) {
            return true
        }
        
        if let email = request.toUserEmail, contactVerifier.isEmailInContacts(email) {
            return true
        }
        
        return false
    }
    
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct StatusBadge: View {
    let status: FriendRequestStatus
    
    var body: some View {
        Text(status.rawValue)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
    
    private var backgroundColor: Color {
        switch status {
        case .pending:
            return .orange
        case .accepted:
            return .green
        case .declined:
            return .red
        case .expired:
            return .gray
        @unknown default:
            return .gray
        }
    }
}

