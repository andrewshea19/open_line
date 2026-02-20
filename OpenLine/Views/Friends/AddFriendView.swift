//
//  AddFriendView.swift
//  OpenLine
//
//  Created by Andrew Shea on 8/8/25.
//
import SwiftUI
import Contacts
import UIKit

struct AddFriendView: View {
    @ObservedObject var viewModel: OpenLineViewModel
    @StateObject private var contactVerifier = ContactVerificationManager.shared
    @State private var searchMethod: SearchMethod = .contacts
    @State private var phoneNumber = ""
    @State private var message = ""
    @State private var isSearching = false
    @State private var isSending = false
    @State private var foundUser: UserProfile?
    @State private var showingContactsAlert = false
    @State private var searchError: String?
    @State private var alertMessage = ""
    @State private var showLocalError = false
    @State private var localErrorMessage = ""
    @Environment(\.dismiss) private var dismiss

    enum SearchMethod: String, CaseIterable {
        case contacts = "Contacts"
        case phone = "Phone Number"
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Search method picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How would you like to add a friend?")
                            .font(TurretTheme.headerFont(size: 13))
                            .foregroundColor(.secondary)
                            

                        Picker("Search Method", selection: $searchMethod) {
                            ForEach(SearchMethod.allCases, id: \.self) { method in
                                Text(method.rawValue).tag(method)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    .padding(.horizontal)
                    .padding(.top)

                    // Search section
                    VStack(spacing: 12) {
                        switch searchMethod {
                        case .contacts:
                            Button(action: {
                                if contactVerifier.hasContactsAccess {
                                    presentContactPicker()
                                } else {
                                    showingContactsAlert = true
                                }
                            }) {
                                HStack {
                                    Image(systemName: "person.crop.rectangle")
                                    Text("Browse Contacts")
                                        .font(TurretTheme.statusFont(size: 15))
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .buttonStyle(BorderlessButtonStyle())

                        case .phone:
                            TextField("Phone Number", text: $phoneNumber)
                                .font(TurretTheme.statusFont(size: 16, weight: .medium))
                                .keyboardType(.phonePad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())

                            Button(action: { searchByPhone() }) {
                                HStack {
                                    if isSearching {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .tint(.white)
                                    }
                                    Text(isSearching ? "Searching..." : "Search")
                                        .font(TurretTheme.statusFont(size: 15))
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(phoneNumber.isEmpty || isSearching ? Color.gray : Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            .disabled(phoneNumber.isEmpty || isSearching)
                        }
                    }
                    .padding(.horizontal)

                    // Found user section
                    if let user = foundUser {
                        Divider()
                            .padding(.vertical, 8)

                        foundUserSection(user)
                            .padding(.horizontal)
                    }

                    Spacer(minLength: 50)
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(TurretTheme.bodyFont(size: 17))
                }
            }
        }
        .alert("Contacts Access", isPresented: $showingContactsAlert) {
            Button("Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("To verify if people are in your contacts, please enable Contacts access in Settings.")
        }
        .alert("Error", isPresented: $showLocalError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(localErrorMessage)
        }
        .onDisappear {
            searchError = nil
            alertMessage = ""
        }
        .onAppear {
            contactVerifier.checkContactsAccess()
        }
    }



    private func foundUserSection(_ user: UserProfile) -> some View {
        VStack(spacing: 16) {
            // User info card
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading) {
                        HStack {
                            Text(user.name)
                                .font(TurretTheme.statusFont(size: 16))

                            if isInContacts(user) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(TurretTheme.ledGreen)
                                    .font(.caption)
                            }
                        }

                        Text(user.phoneNumber)
                            .font(TurretTheme.captionFont(size: 13))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // LED indicator
                    ZStack {
                        Circle()
                            .fill(statusColor(for: user.currentStatus).opacity(0.2))
                            .frame(width: 18, height: 18)
                            .blur(radius: 2)

                        Circle()
                            .fill(TurretTheme.panelDark)
                            .frame(width: 14, height: 14)

                        Circle()
                            .fill(statusColor(for: user.currentStatus))
                            .frame(width: 8, height: 8)
                    }
                }

                if isInContacts(user) {
                    HStack {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .foregroundColor(TurretTheme.ledGreen)
                        Text("This person is in your contacts")
                            .font(TurretTheme.captionFont(size: 12))
                            .foregroundColor(TurretTheme.ledGreen)
                    }
                    .padding(.vertical, 2)
                } else {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(TurretTheme.ledAmber)
                        Text("This person is not in your contacts")
                            .font(TurretTheme.captionFont(size: 12))
                            .foregroundColor(TurretTheme.ledAmber)
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(12)
            .glassCard(cornerRadius: 16, padding: 0)

            // Message input
            VStack(alignment: .leading, spacing: 8) {
                Text("Message (Optional)")
                    .font(TurretTheme.headerFont(size: 13))
                    .foregroundColor(.secondary)
                    

                TextEditor(text: $message)
                    .font(TurretTheme.bodyFont(size: 15))
                    .frame(minHeight: 100)
            }

            // Send request button
            Button {
                sendFriendRequest(to: user)
            } label: {
                HStack {
                    if isSending {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    }
                    Text(isSending ? "Sending..." : "Send Friend Request")
                        .font(TurretTheme.statusFont(size: 15))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundColor(.white)
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(BorderlessButtonStyle())
            .disabled(isSearching || isSending)
            .opacity(isSearching || isSending ? 0.6 : 1.0)
        }
    }

    private func isInContacts(_ user: UserProfile) -> Bool {
        let contactVerifier = ContactVerificationManager.shared

        if contactVerifier.isPhoneNumberInContacts(user.phoneNumber) {
            return true
        }

        if let email = user.email, contactVerifier.isEmailInContacts(email) {
            return true
        }

        return false
    }

    private func presentContactPicker() {
        ContactPickerPresenter.shared.present(
            onContactSelected: { [self] contact in
                self.handleContactSelection(contact)
            },
            onDismiss: { }
        )
    }

    private func handleContactSelection(_ contact: CNContact) {
        guard let phoneNumberObj = contact.phoneNumbers.first else {
            localErrorMessage = "No phone number found for this contact"
            showLocalError = true
            return
        }

        let phoneNumber = phoneNumberObj.value.stringValue
        let normalizedPhone = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()

        guard !normalizedPhone.isEmpty else {
            localErrorMessage = "Invalid phone number format"
            showLocalError = true
            return
        }

        self.phoneNumber = normalizedPhone
        searchByPhone()
    }

    private func searchByPhone() {
        guard !phoneNumber.isEmpty else { return }

        let normalizedPhone = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()

        guard !normalizedPhone.isEmpty else {
            localErrorMessage = "Please enter a valid phone number"
            showLocalError = true
            return
        }

        isSearching = true
        foundUser = nil

        // Check if user is trying to add themselves
        if let currentPhone = SyncManager.shared.currentUserProfile?.phoneNumber,
           normalizedPhone == currentPhone {
            isSearching = false
            localErrorMessage = "You can't add yourself as a friend."
            showLocalError = true
            return
        }

        SyncManager.shared.searchForUsersByPhone(normalizedPhone) { result in
            DispatchQueue.main.async {
                self.isSearching = false
                switch result {
                case .success(let user):
                    if let user = user {
                        self.foundUser = user
                        self.searchError = nil
                    } else {
                        self.foundUser = nil
                        self.localErrorMessage = "No user found with this phone number. They may not be on OpenLine yet or may not have marked themselves as discoverable."
                        self.showLocalError = true
                    }
                case .failure(let error):
                    self.foundUser = nil
                    self.localErrorMessage = error.errorDescription ?? "Failed to search. Please check your connection and try again."
                    self.showLocalError = true
                }
            }
        }
    }

    private func sendFriendRequest(to user: UserProfile) {
        // Check if already a friend
        if viewModel.friends.contains(where: { $0.phoneNumber == user.phoneNumber }) {
            localErrorMessage = "\(user.name) is already your friend."
            showLocalError = true
            return
        }

        // Check if already sent a request
        if viewModel.sentFriendRequests.contains(where: { $0.toUserPhone == user.phoneNumber }) {
            localErrorMessage = "You already have a pending friend request to \(user.name)."
            showLocalError = true
            return
        }

        isSending = true

        guard let currentProfile = SyncManager.shared.currentUserProfile else {
            isSending = false
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 500_000_000)
                self.viewModel.errorMessage = "Missing user profile. Please restart the app."
                self.viewModel.showError = true
            }
            return
        }

        SyncManager.shared.sendFriendRequest(to: user, message: message.isEmpty ? nil : message) { result in
            Task { @MainActor in
                self.isSending = false
                switch result {
                case .success:
                    let outgoingRequest = FriendRequest.outgoing(
                        toUserID: user.uniqueIdentifier,
                        toUserName: user.name,
                        toUserPhone: user.phoneNumber,
                        toUserEmail: user.email,
                        fromUserID: currentProfile.uniqueIdentifier,
                        fromUserName: currentProfile.name,
                        fromUserPhone: currentProfile.phoneNumber,
                        fromUserEmail: currentProfile.email,
                        message: self.message.isEmpty ? nil : self.message
                    )
                    self.viewModel.addSentFriendRequest(outgoingRequest)
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    self.dismiss()
                case .failure(let error):
                    let errorMsg = error.errorDescription ?? "Failed to send friend request. Please try again."
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    self.viewModel.errorMessage = errorMsg
                    self.viewModel.showError = true
                }
            }
        }
    }

    private func statusColor(for status: String) -> Color {
        switch StatusType(rawValue: status) {
        case .available:
            return TurretTheme.ledGreen
        case .unavailable:
            return TurretTheme.ledRed
        default:
            return TurretTheme.ledAmber
        }
    }
}
