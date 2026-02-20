//
//  ProfileSetupView.swift
//  OpenLine
//
//  Created by Andrew Shea on 8/8/25.
//
import SwiftUI

struct ProfileSetupView: View {
    @Binding var isPresented: Bool
    @StateObject private var syncManager = SyncManager.shared
    @State private var name = ""
    @State private var phoneNumber = ""
    @State private var email = ""
    @State private var isDiscoverable = true

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Your Name", text: $name)
                        .font(TurretTheme.bodyFont(size: 16, weight: .medium))
                    TextField("Phone Number", text: $phoneNumber)
                        .font(TurretTheme.bodyFont(size: 16, weight: .medium))
                        .keyboardType(.phonePad)
                    TextField("Email (Optional)", text: $email)
                        .font(TurretTheme.bodyFont(size: 16, weight: .medium))
                        .keyboardType(.emailAddress)
                } header: {
                    Text("Profile Information")
                        .font(TurretTheme.headerFont(size: 13))
                } footer: {
                    Text("This information helps friends find and connect with you.")
                        .font(TurretTheme.captionFont(size: 12))
                }

                Section {
                    Toggle("Allow others to find me", isOn: $isDiscoverable)
                        .font(TurretTheme.bodyFont(size: 15, weight: .medium))
                        .tint(TurretTheme.ledGreen)
                } footer: {
                    Text("When enabled, friends can find you by phone number or email to send friend requests.")
                        .font(TurretTheme.captionFont(size: 12))
                }
            }
            .navigationTitle("Setup Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProfile()
                    }
                    .disabled(name.isEmpty || phoneNumber.isEmpty)
                    .font(TurretTheme.statusFont(size: 17))
                }
            }
        }
        .onAppear {
            loadProfileData()
        }
    }

    private func loadProfileData() {
        if let profile = syncManager.currentUserProfile {
            name = profile.name
            phoneNumber = profile.phoneNumber
            email = profile.email ?? ""
            isDiscoverable = profile.isDiscoverable
        }
    }

    private func saveProfile() {
        let normalizedPhone = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()

        let profile = UserProfile(
            name: name,
            phoneNumber: normalizedPhone,
            email: email.isEmpty ? nil : email
        )

        var updatedProfile = profile
        updatedProfile.isDiscoverable = isDiscoverable

        syncManager.saveUserProfile(updatedProfile)
        isPresented = false
    }
}
