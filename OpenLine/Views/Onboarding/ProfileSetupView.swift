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
                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                    TextField("Email (Optional)", text: $email)
                        .keyboardType(.emailAddress)
                } header: {
                    Text("Profile Information")
                } footer: {
                    Text("This information helps friends find and connect with you.")
                }
                
                Section {
                    Toggle("Allow others to find me", isOn: $isDiscoverable)
                } footer: {
                    Text("When enabled, friends can find you by phone number or email to send friend requests.")
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
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            if let profile = syncManager.currentUserProfile {
                name = profile.name
                phoneNumber = profile.phoneNumber
                email = profile.email ?? ""
                isDiscoverable = profile.isDiscoverable
            }
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
